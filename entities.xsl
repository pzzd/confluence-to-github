<?xml version="1.0" encoding="UTF-8"?>
<!--
Transform a Confluence XML format space export to multiple xml pages.
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:exsl="http://exslt.org/common"
                extension-element-prefixes="exsl">

  <xsl:output method="xml" standalone="yes" indent="yes"/>

  <xsl:param name="output-path" select="'out/'"/>
  <xsl:param name="space" select="'storage'"/>
  <xsl:param name="space-category" select="'storage-team'"/>

  <xsl:template match="@*|node()" priority="-1">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="text()">
    <xsl:if test="normalize-space(.) != ''">
      <xsl:value-of select="."/>
    </xsl:if>
  </xsl:template>

  <xsl:template name="string-replace-all">
    <xsl:param name="text"/>
    <xsl:param name="replace"/>
    <xsl:param name="by"/>
    <xsl:choose>
      <xsl:when test="$text = '' or $replace = ''or not($replace)">
        <xsl:value-of select="$text"/>
      </xsl:when>
      <xsl:when test="contains($text, $replace)">
        <xsl:value-of select="substring-before($text,$replace)" disable-output-escaping="yes"/>
        <xsl:value-of select="$by" disable-output-escaping="yes"/>
        <xsl:call-template name="string-replace-all">
          <xsl:with-param name="text" select="substring-after($text,$replace)"/>
          <xsl:with-param name="replace" select="$replace"/>
          <xsl:with-param name="by" select="$by"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text" disable-output-escaping="yes"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="object[@class='Page']">
    <!-- 
      bad title characters \ / : * ? " < > | & ( )
    -->
    <xsl:variable name="was" select="' \/:*?\|&quot;&lt;&gt;&amp;\(\)'"/>
    <xsl:variable name="now" select="'-----------'"/>
    <xsl:message>[<xsl:value-of select="property[@name='title']"/>] to [<xsl:value-of select="translate(property[@name='title'],$was,$now)"/>]
    </xsl:message>
    <exsl:document href="{$output-path}/page-xml/{translate(property[@name='title'],$was,$now)}.xml" format="xml" standalone="no" indent="yes" doctype-system="../../page.dtd">
      <page
        xmlns:ac="http://www.atlassian.com/schema/confluence/4/ac/"
        xmlns:ri="http://www.atlassian.com/schema/confluence/4/ri/"
      >
        <space>
          <xsl:value-of select="$space"/>
        </space>
        <title>
          <xsl:value-of select="property[@name='title']"/>
        </title>
        <lower-title>
          <xsl:value-of select="property[@name='lowerTitle']"/>
        </lower-title>
        <body>
          <!-- fixup nested CDATA closes in body -->
          <xsl:call-template name="string-replace-all">
            <xsl:with-param name="text" select="/hibernate-generic/object[@class='BodyContent' and id=current()/collection[@name='bodyContents']/element[@class='BodyContent']/id]/property[@name='body']"/>
            <xsl:with-param name="replace" select="']] >'"/>
            <xsl:with-param name="by" select="']]>'"/>
          </xsl:call-template>
        </body>
        <xsl:if test="$space-category">
          <category>
            <xsl:value-of select="$space-category"/>
          </category>
        </xsl:if>
        <category>confluence</category>
      </page>
    </exsl:document>
  </xsl:template>

  <xsl:template match="id" mode="image">
    <xsl:variable name="attachment-id" select="string(text())"/>
    <xsl:message>attachment-id=[<xsl:value-of select="$attachment-id"/>]</xsl:message>
<!--    <xsl:if test="/hibernate-generic/object[@class='Attachment' and id = $attachment-id and '' = property[@name = 'originalVersionId']]">-->
    <xsl:if test="/hibernate-generic/object[@class='Attachment' and id = $attachment-id]">
      <image attachment="attachments/{../../../id}/{$attachment-id}/{/hibernate-generic/object[@class='Attachment' and id = $attachment-id]/property[@name = 'version']}" path="images/{$space}/{/hibernate-generic/object[@class='Attachment' and id = $attachment-id]/property[@name = 'title']}"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="/">
    <!-- 
      export will include old versions of current pages and pages that 
      have been deleted. we only want to select only pages with a content status of 'current'.
    -->
    <xsl:apply-templates select="/hibernate-generic/object[@class='Page' and boolean(property[@name='contentStatus'][text()='current'])]"/>

    <!-- 
      create a mapping document for attachments to wiki images

      attachments/$page-id/$attachment-id/$version - - > images/$space/$filename
      attachments/100434301/104595714/1            - - > images/services/intellij_idea_annotation_processors.gif
    -->
    <exsl:document href="{$output-path}image-mappings.xml" format="xml" standalone="yes" indent="yes">
      <images>
<!--        <xsl:apply-templates select="/hibernate-generic/object[@class='Page' and boolean(collection[@name='historicalVersions'])]/collection[@name = 'attachments']/element[@class = 'Attachment']/id[@name = 'id']" mode="image"/>-->
        <xsl:apply-templates select="/hibernate-generic/object[@class='Page']/collection[@name = 'attachments']/element[@class = 'Attachment']/id[@name = 'id']" mode="image"/>
      </images>
    </exsl:document>
  </xsl:template>

</xsl:stylesheet>
