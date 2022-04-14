// Copyright (c) 2021-2022 THL A29 Limited
//
// This source code file is made available under MIT License
// See LICENSE for details
// ==============================================================================

/**
 * 开启第一次代码分析
 */

import React, { useEffect, useState } from 'react';
import { useHistory } from 'react-router-dom';
import cn from 'classnames';
import { get, pick, find } from 'lodash';
import { Modal, Form, Input, Select, Radio, Row, Col, Checkbox, message, Tag } from 'coding-oa-uikit';

import { getProjectRouter } from '@src/utils/getRoutePath';
import { getLanguages, getTags } from '@src/services/schemes';
import { initRepos } from '@src/services/projects';

import { SCAN_LIST } from '../../schemes/constants';
import style from '../style.scss';

import ScanModal from './scan-modal';

const { Option } = Select;

interface FirstModalProps {
  orgSid: string;
  teamName: string;
  repoId: number;
  visible: boolean;
  templates: any[];
  onClose: () => void;
}

const FirstModal = (props: FirstModalProps) => {
  const history = useHistory();
  const [form] = Form.useForm();
  const [languages, setLanguages] = useState<any>([]);
  const [tags, setTags] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [scan, setScan] = useState({
    visible: false,
    projectId: -1,
  });

  const { orgSid, teamName, visible, repoId, templates, onClose } = props;

  useEffect(() => {
    (async () => {
      setTags(get(await getTags(), 'results', []));
      setLanguages(get(await getLanguages(), 'results', []));
    })();
  }, []);

  const onFinish = (data: any) => {
    const { funcList = [] } = data;
    // 开源版需要隐藏tag，默认赋予tag Codedog_Linux
    const tag = tags.filter(item => item.public && item.name === 'Codedog_Linux').pop() || tags.pop();
    data = data.type === 'create' ? {
      branch: data.branch,
      scan_scheme: {
        name: '默认',
        ...pick(data, ['languages', 'tag']),
        ...SCAN_LIST.map(item => ({ [item.value]: funcList.includes(item.value) })).reduce(
          (acc, cur) => ({ ...acc, ...cur }),
          {},
        ),
        build_cmd: null,
        envs: null,
        pre_cmd: null,
        build_flag: false,
        tag: tag.name || 'Codedog_Linux',
      },
    } : {
      branch: data.branch,
      custom_scheme_name: find(templates, { id: data.global_scheme_id })?.name,
      global_scheme_id: data.global_scheme_id,
    };

    setLoading(true);
    initRepos(orgSid, teamName, repoId, data).then((res) => {
      message.success('分支项目创建成功');
      onReset();
      history.push(`${getProjectRouter(orgSid, teamName, repoId, res.id)}/overview`);
      setScan({
        visible: true,
        projectId: res.id,
      });
    })
      .finally(() => {
        setLoading(false);
      });
  };

  const onReset = () => {
    form.resetFields();
    onClose();
  };

  return (
    <>
      <Modal
        title='开启第一次代码分析'
        width={520}
        visible={visible}
        className={style.newProjectModal}
        okButtonProps={{ loading }}
        onCancel={onReset}
        onOk={() => form.validateFields().then(onFinish)}
      >
        <Form
          layout='vertical'
          form={form}
          initialValues={{
            branch: 'master',
          }}
        >
          <Form.Item
            name='branch'
            label='分支名称'
            rules={[{ required: true, message: '请输入分支名称' }]}
          >
            <Input placeholder='请输入分支名称' />
          </Form.Item>
          <Form.Item
            name="type"
            label=""
            initialValue="template"
          >
            <Radio.Group style={{ width: '100%' }} >
              <Row gutter={12}>
                <Col span={7}>
                  <Radio value="template">分析方案模板</Radio>
                </Col>
                <Col span={7}>
                  <Radio value="create">创建分析方案</Radio>
                </Col>
              </Row>
            </Radio.Group>
          </Form.Item>
          <Form.Item
            noStyle
            shouldUpdate={(prevValues, currentValues) => prevValues.type !== currentValues.type
            }
          >
            {({ getFieldValue }) => (getFieldValue('type') === 'create' ? (
              <>
                <Form.Item
                  name="languages"
                  label="分析语言"
                  rules={[{ required: true, message: '请选择分析语言' }]}
                >
                  <Select
                    placeholder="请选择分析语言"
                    style={{ width: '100%' }}
                    mode='multiple'
                    optionFilterProp='children'
                  >
                    {languages.map((item: any) => (
                      <Option key={item.name} value={item.name}>
                        {item.display_name}
                      </Option>
                    ))}
                  </Select>
                </Form.Item>
                <Form.Item
                  name="tag"
                  label="运行环境"
                  rules={[{ required: true, message: '请选择运行环境' }]}
                >
                  <Radio.Group>
                    <Row>
                      {tags.map((item: any) => item.public && (
                        <Col
                          span={8}
                          key={item.name}
                          style={{ marginBottom: 8 }}
                        >
                          <Radio value={item.name}>
                            {item.name}
                          </Radio>
                        </Col>
                      ))}
                    </Row>
                  </Radio.Group>
                </Form.Item>
                <Form.Item
                  name="funcList"
                  label="功能开启"
                  initialValue={[
                    'lint_enabled',
                    'cc_scan_enabled',
                    'dup_scan_enabled',
                    'cloc_scan_enabled',
                  ]}
                  style={{ marginBottom: 0 }}
                >
                  <Checkbox.Group>
                    <Row gutter={16}>
                      {SCAN_LIST.map((item: any) => (
                        <Col span={6} key={item.value}>
                          <Checkbox value={item.value}>
                            {item.label}
                          </Checkbox>
                        </Col>
                      ))}
                    </Row>
                  </Checkbox.Group>
                </Form.Item>
              </>
            ) : (
              <Form.Item
                name="global_scheme_id"
                rules={[{ required: true, message: '请选择模板' }]}
              >
                <Select
                  showSearch
                  placeholder="请选择分析方案模板"
                  optionLabelProp="label"
                  optionFilterProp="label"
                >
                  {templates.map((item: any) => (
                    <Option key={item.id} value={item.id} label={item.name}>
                      <div className={style.tmpl}>
                        <span>{item.name}</span>
                        <Tag className={cn(style.tmplTag, { [style.sys]: item.scheme_key === 'public' })}
                        >{item.scheme_key === 'public' ? '系统' : '自定义'}</Tag>
                      </div>
                    </Option>
                  ))}
                </Select>
              </Form.Item>
            ))}
          </Form.Item>
        </Form>
      </Modal>
      <ScanModal
        orgSid={orgSid}
        teamName={teamName}
        visible={scan.visible}
        repoId={repoId}
        projectId={scan.projectId}
        onClose={() => setScan({ ...scan, visible: false })}
      />
    </>
  );
};

export default FirstModal;
